FROM ruby:4.0.1-alpine3.22
ARG BUNDLE_INSTALL_CMD
ENV RACK_ENV=development
ENV WORD_LIST_FILE='./tmp/wordlist'
ENV GOVNOTIFY_BEARER_TOKEN ''

WORKDIR /usr/src/app

COPY . ./

RUN apk --no-cache add --virtual .build-deps build-base && \
  apk --no-cache add mysql-dev && \
  ${BUNDLE_INSTALL_CMD} && \
  apk del .build-deps

COPY entrypoint.sh /usr/bin/
RUN chmod +x /usr/bin/entrypoint.sh
ENTRYPOINT ["entrypoint.sh"]

CMD ["bundle", "exec", "puma", "-p", "8080", "--quiet", "--threads", "8:32"]
