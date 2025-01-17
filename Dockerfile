FROM ruby:3.4.1-alpine
ARG BUNDLE_INSTALL_CMD
ENV RACK_ENV=development
ENV WORD_LIST_FILE='./tmp/wordlist'

WORKDIR /usr/src/app

COPY Gemfile Gemfile.lock .ruby-version ./

RUN apk --no-cache add --virtual .build-deps build-base && \
  apk --no-cache add mysql-dev && \
  ${BUNDLE_INSTALL_CMD} && \
  apk del .build-deps

COPY . .

ENV GOVNOTIFY_BEARER_TOKEN ''

COPY entrypoint.sh /usr/bin/
RUN chmod +x /usr/bin/entrypoint.sh
ENTRYPOINT ["entrypoint.sh"]

CMD ["bundle", "exec", "puma", "-p", "8080", "--quiet", "--threads", "8:32"]
